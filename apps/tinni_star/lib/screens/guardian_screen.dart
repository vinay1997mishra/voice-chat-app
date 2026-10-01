import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  bool loading = true;
  Map<String, dynamic> data = const <String, dynamic>{};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.guardianState(account.authToken);
      if (!mounted) return;
      setState(() {
        data = value;
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

  ImageProvider? _avatar(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final guardian = data['guardian'] is Map
        ? Map<String, dynamic>.from(data['guardian'] as Map)
        : null;
    final supporters = data['supporters'] is List
        ? List<Map<String, dynamic>>.from(
            (data['supporters'] as List).whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : const <Map<String, dynamic>>[];
    final candidateThreshold =
        (data['candidate_threshold'] as num?)?.toInt() ?? 1000;
    final guardianThreshold =
        (data['guardian_threshold'] as num?)?.toInt() ?? 10000;
    final windowDays = (data['window_days'] as num?)?.toInt() ?? 30;

    return Scaffold(
      key: const Key('guardian-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text('My Guardian'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            RoyalPanel(
              accentColor: RoyalPalette.deepGold,
              child: Column(
                children: [
                  if (guardian == null)
                    const Icon(
                      Icons.shield_outlined,
                      color: RoyalPalette.gold,
                      size: 54,
                    )
                  else
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: RoyalPalette.nearBlack,
                      backgroundImage:
                          _avatar(guardian['avatar_data_url']?.toString()),
                      child: _avatar(
                                guardian['avatar_data_url']?.toString(),
                              ) ==
                              null
                          ? const Icon(
                              Icons.shield_rounded,
                              color: RoyalPalette.gold,
                              size: 38,
                            )
                          : null,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    guardian == null
                        ? 'No Guardian yet'
                        : guardian['display_name']?.toString() ?? 'Guardian',
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (guardian != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${guardian['points'] ?? 0} guardian points',
                      style: const TextStyle(
                        color: RoyalPalette.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            RoyalPanel(
              accentColor: RoyalPalette.deepGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guardian rules',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gift contribution in the last $windowDays days creates Guardian points. '
                    'A supporter becomes eligible at $candidateThreshold points. '
                    'The #1 supporter becomes your Guardian after reaching $guardianThreshold points.',
                    style: const TextStyle(
                      color: RoyalPalette.muted,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Top supporters',
              style: TextStyle(
                color: RoyalPalette.gold,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              RoyalPanel(
                child: Text(
                  error!,
                  style: const TextStyle(color: RoyalPalette.muted),
                ),
              )
            else if (supporters.isEmpty)
              const RoyalPanel(
                child: Text(
                  'No Guardian points in the current 30-day window.',
                  style: TextStyle(color: RoyalPalette.muted),
                ),
              )
            else
              for (final row in supporters.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RoyalPanel(
                    padding: const EdgeInsets.all(9),
                    accentColor: (row['rank'] as num?)?.toInt() == 1
                        ? RoyalPalette.gold
                        : RoyalPalette.deepGold,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: RoyalPalette.nearBlack,
                          backgroundImage:
                              _avatar(row['avatar_data_url']?.toString()),
                          child: _avatar(
                                    row['avatar_data_url']?.toString(),
                                  ) ==
                                  null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: RoyalPalette.gold,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${row['rank']}  ${row['display_name']}',
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${row['flag_emoji'] ?? ''}  ID ${row['user_id']}',
                                style: const TextStyle(
                                  color: RoyalPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${row['points']}',
                          style: const TextStyle(
                            color: RoyalPalette.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
