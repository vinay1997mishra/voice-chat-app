import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'family_home_screen.dart';

class FamilyRankingScreen extends StatefulWidget {
  const FamilyRankingScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FamilyRankingScreen> createState() => _FamilyRankingScreenState();
}

class _FamilyRankingScreenState extends State<FamilyRankingScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> families = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.familyList(account.authToken, limit: 100),
        widget.state.backend.familyState(account.authToken),
      ]);
      widget.state.family.applyRemote(
        Map<String, dynamic>.from(results[1] as Map),
      );
      if (!mounted) return;
      setState(() {
        families = List<Map<String, dynamic>>.from(results[0] as List);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _createFamily() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    if (widget.state.family.exists) {
      _openMyFamily();
      return;
    }

    final nameController = TextEditingController();
    final tagController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('create-family-name'),
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Family name'),
            ),
            TextField(
              key: const Key('create-family-tag'),
              controller: tagController,
              maxLength: 12,
              decoration: const InputDecoration(labelText: 'Family tag'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('create-family-submit'),
            onPressed: () {
              final name = nameController.text.trim();
              final tag = tagController.text.trim();
              if (name.length < 2 || tag.length < 2) return;
              Navigator.pop(dialogContext, (name, tag));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
    tagController.dispose();
    if (result == null || !mounted) return;

    try {
      await widget.state.backend.createFamily(
        account.authToken,
        name: result.$1,
        tag: result.$2,
      );
      final state = await widget.state.backend.familyState(account.authToken);
      widget.state.family.applyRemote(state);
      await _load();
      if (!mounted) return;
      _openMyFamily();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _openMyFamily() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyHomeScreen(state: widget.state),
      ),
    ).then((_) => _load());
  }

  void _openFamily(Map<String, dynamic> family) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyHomeScreen(
          state: widget.state,
          previewFamilyId: family['id']?.toString(),
          previewName: family['name']?.toString(),
          previewTag: family['tag']?.toString(),
        ),
      ),
    ).then((_) => _load());
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return (value / 1000000000).toStringAsFixed(1) + 'B';
    }
    if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'M';
    }
    if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('family-ranking-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Top Families',
          style: TextStyle(
            color: FeaturePalette.family,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('family-ranking-list'),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  if (families.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No Families have been created yet.',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    ),
                  for (var index = 0; index < families.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        key: Key('family-rank-row-' + index.toString()),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openFamily(families[index]),
                        child: RoyalPanel(
                          gradient:
                              FeaturePalette.glow(FeaturePalette.family),
                          accentColor: FeaturePalette.family,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '#${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: FeaturePalette.family,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: FeaturePalette.family
                                    .withValues(alpha: 0.18),
                                child: Text(
                                  (families[index]['name']?.toString() ?? 'F')
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: FeaturePalette.family,
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
                                      families[index]['name']?.toString() ??
                                          'Family',
                                      style: const TextStyle(
                                        color: RoyalPalette.cream,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      (families[index]['tag']?.toString() ??
                                              'FM') +
                                          ' • Lv.' +
                                          ((families[index]['level'] is Map
                                                  ? (families[index]['level']
                                                          as Map)['level']
                                                  : 1)
                                              .toString()) +
                                          ' • ' +
                                          ((families[index]['member_count']
                                                      as num?)
                                                  ?.toInt() ??
                                              0)
                                              .toString() +
                                          ' members',
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
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: FeaturePalette.family,
                                    size: 18,
                                  ),
                                  Text(
                                    _compact(
                                      (families[index]['experience'] as num?)
                                              ?.toInt() ??
                                          0,
                                    ),
                                    style: const TextStyle(
                                      color: FeaturePalette.wallet,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const RoyalPanel(
                    child: Text(
                      'Family coin progression uses the Tinni Star 100× '
                      'reference scale: 20,000 reference coins = '
                      '2,000,000 Tinni coins.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('family-create-button'),
                onPressed: _createFamily,
                child: Text(
                  widget.state.family.exists ? 'My Family' : 'Create',
                ),
              ),
            ),
            if (widget.state.family.exists) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('family-ranking-open-button'),
                  onPressed: _openMyFamily,
                  child: const Text('Open'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
