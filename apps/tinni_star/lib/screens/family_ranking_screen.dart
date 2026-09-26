import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../community/family_service.dart';
import '../ui/royal_theme.dart';
import 'family_home_screen.dart';

class FamilyRankingScreen extends StatefulWidget {
  const FamilyRankingScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FamilyRankingScreen> createState() => _FamilyRankingScreenState();
}

class _FamilyRankingScreenState extends State<FamilyRankingScreen> {
  String _scope = 'Local';

  static const _families = [
    _FamilyRankItem('welcome', 'Welcome Uttarakhand', 'UK06', 2590000),
    _FamilyRankItem('bs', 'BS PATEL FAMILY', 'PATEL 2227', 2430000),
    _FamilyRankItem('lion', 'LION KING FAMILY', 'LION KING', 1800000),
    _FamilyRankItem('mumbai', 'Mumbai girl', 'mumbai', 1790000),
    _FamilyRankItem('jay', 'Jay Shri Shyam', 'Jay Shri S', 1540000),
    _FamilyRankItem('kuch', 'kuch log achy s', 'AM', 1530000),
    _FamilyRankItem('sakshi', 'Sakshi world', 'Maruti', 1230000),
    _FamilyRankItem('aryan', 'Aryan family', 'Mr Aryan 1', 1140000),
    _FamilyRankItem('warrior', 'Indian warrior', 'Mr Indian', 1130000),
  ];

  Future<void> _createFamily() async {
    if (widget.state.family.exists) {
      _openMyFamily();
      return;
    }
    final nameController = TextEditingController();
    final tagController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('create-family-name'),
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Family name'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('create-family-tag'),
              controller: tagController,
              decoration: const InputDecoration(labelText: 'Family tag'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('create-family-submit'),
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  tagController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true || !mounted) {
      nameController.dispose();
      tagController.dispose();
      return;
    }

    final userId = widget.state.auth.current?.userId ?? '10000000';
    widget.state.family.create(
      familyName: nameController.text,
      familyTag: tagController.text,
      head: FamilyMember(
        userId: userId,
        name: 'Tinni User',
        role: FamilyRole.head,
      ),
    );
    widget.state.family.updateNotice(
      'welcome ' + nameController.text.trim() + ' members ❤️',
    );
    nameController.dispose();
    tagController.dispose();
    if (!mounted) return;
    _openMyFamily();
  }

  void _openMyFamily() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyHomeScreen(state: widget.state),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _showJoinList() async {
    if (widget.state.family.exists) {
      _openMyFamily();
      return;
    }
    final selected = await showModalBottomSheet<_FamilyRankItem>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            const GoldSectionTitle('Choose a family'),
            const SizedBox(height: 8),
            for (final family in _families.take(6))
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FeaturePalette.family.withValues(alpha: 0.18),
                    border: Border.all(color: FeaturePalette.family),
                    boxShadow: [
                      BoxShadow(
                        color: FeaturePalette.family.withValues(alpha: 0.42),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    family.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: FeaturePalette.family,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(family.name),
                subtitle: Text(family.tag),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: FeaturePalette.family,
                ),
                onTap: () => Navigator.pop(context, family),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyHomeScreen(
          state: widget.state,
          previewName: selected.name,
          previewTag: selected.tag,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openFamily(_FamilyRankItem family) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyHomeScreen(
          state: widget.state,
          previewName: family.name,
          previewTag: family.tag,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('family-ranking-screen'),
      appBar: AppBar(
        title: const Text(
          'Top Families of the Month',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('family-ranking-scope'),
            initialValue: _scope,
            onSelected: (value) => setState(() => _scope = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Local', child: Text('Local')),
              PopupMenuItem(value: 'Global', child: Text('Global')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  _scope,
                  style: const TextStyle(
                    color: RoyalPalette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              key: const Key('family-ranking-list'),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              itemCount: _families.length,
              separatorBuilder: (context, index) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final family = _families[index];
                final rank = index + 7;
                return InkWell(
                  key: Key('family-rank-row-' + index.toString()),
                  onTap: () => _openFamily(family),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFE783),
                          Color(0xFFD0A936),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF725200),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 31,
                          child: Text(
                            rank.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: const Color(0xFF7A5515),
                          child: Text(
                            family.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                family.name + ' 🇮🇳',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1487A5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  family.tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.deepOrange,
                          size: 17,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _compact(family.score),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!widget.state.family.exists)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'You have not joined the family yet. Please create or join it first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RoyalPalette.muted,
                  fontSize: 10,
                ),
              ),
            ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('family-create-button'),
                    onPressed: _createFamily,
                    child: Text(
                      widget.state.family.exists ? 'My family' : 'Create',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('family-ranking-join-button'),
                    onPressed: _showJoinList,
                    child: Text(
                      widget.state.family.exists ? 'Open' : 'Join',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(2) + 'M';
    }
    if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    }
    return value.toString();
  }
}

class _FamilyRankItem {
  const _FamilyRankItem(
    this.id,
    this.name,
    this.tag,
    this.score,
  );

  final String id;
  final String name;
  final String tag;
  final int score;
}
