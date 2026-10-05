import 'dart:convert';

import 'package:flutter/material.dart';
import 'animated_avatar_frame.dart';

class RocketRewardsPanel extends StatelessWidget {
  const RocketRewardsPanel({super.key, required this.level, required this.data});
  final int level;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final top = (data?['top'] as List? ?? const []).whereType<Map>().toList();
    final bases = [400000, 200000, 100000];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (index) {
          final row = index < top.length ? top[index] : null;
          final source = row?['avatar_data_url'] as String?;
          ImageProvider? image;
          if (source != null && source.startsWith('data:image/')) {
            try { image = MemoryImage(base64Decode(source.split(',').last)); } catch (_) {}
          } else if (source != null && source.startsWith('https://')) {
            image = NetworkImage(source);
          }
          final avatar = image != null
              ? Image(image: image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white))
              : const Icon(Icons.person, color: Colors.white);
          final rank = index + 1;
          final frame = row?['frame_id'] as String? ?? 'rocket-l$level-top$rank';
          final coins = (row?['coins'] as num?)?.toInt() ?? bases[index] * level;
          return Expanded(
            child: Container(
              key: Key('rocket-top-$rank-reward'),
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF101C32),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: [const Color(0xFFFFD166), const Color(0xFFD9E7F3), const Color(0xFFFFAA79)][index].withValues(alpha: .65)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('TOP $rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                AnimatedAvatarFrame(frameId: frame, size: 46, child: ClipOval(child: avatar)),
                Text(row?['name']?.toString() ?? 'Awaiting sender', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFDCE5F5), fontSize: 10)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.workspace_premium, color: Color(0xFFFFD166), size: 16),
                  Flexible(child: Text('Rocket $level', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 10))),
                ]),
                Text('${coins ~/ 100000} L coins', style: const TextStyle(color: Color(0xFF8DF1CE), fontSize: 11, fontWeight: FontWeight.w800)),
                Text(row?['awarded'] == true ? 'Received' : 'On launch',
                  style: const TextStyle(color: Color(0xFF93A7CB), fontSize: 9)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
