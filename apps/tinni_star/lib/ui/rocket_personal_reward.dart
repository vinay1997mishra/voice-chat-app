import 'package:flutter/material.dart';
import 'animated_avatar_frame.dart';

/// A received reward is accepted only for the signed-in viewer and this launch.
class RocketPersonalReward {
  const RocketPersonalReward({
    required this.userId, required this.level, required this.coins,
    required this.credited, this.frameId, this.medal,
  });
  final String userId;
  final int level, coins;
  final bool credited;
  final String? frameId, medal;

  static RocketPersonalReward? fromResponse(
    Map<String, dynamic> response, {required String viewerId, required int level},
  ) {
    final raw = response['reward'];
    if (viewerId.isEmpty || response['ok'] != true ||
        response['level'] != level || raw is! Map ||
        raw['user_id']?.toString() != viewerId || raw['awarded'] != true) {
      return null;
    }
    final coins = (raw['coins'] as num? ?? 0).toInt();
    final frame = raw['frame_id']?.toString();
    final medal = raw['medal']?.toString();
    if (coins <= 0 && (frame == null || frame.isEmpty) &&
        (medal == null || medal.isEmpty)) return null;
    return RocketPersonalReward(
      userId: viewerId, level: level, coins: coins < 0 ? 0 : coins,
      credited: raw['credited'] == true, frameId: frame, medal: medal,
    );
  }
}

class RocketPersonalRewardCard extends StatelessWidget {
  const RocketPersonalRewardCard({
    super.key, required this.reward, required this.onClose,
  });
  final RocketPersonalReward reward;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Card(
        key: const Key('rocket-personal-reward'),
        color: const Color(0xFF101C32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFFD479)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('Your Rocket ${reward.level} reward',
                  style: const TextStyle(color: Color(0xFFFFD479),
                    fontSize: 18, fontWeight: FontWeight.w900))),
                IconButton(
                  key: const Key('rocket-personal-reward-close'),
                  tooltip: 'Close your reward',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ]),
              if (reward.frameId != null && reward.frameId!.isNotEmpty) ...[
                AnimatedAvatarFrame(
                  frameId: reward.frameId!, size: 84,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF20304C),
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                ),
                const Text('Animated frame received',
                  style: TextStyle(color: Colors.white)),
              ],
              if (reward.coins > 0) ...[
                const SizedBox(height: 12),
                const Icon(Icons.monetization_on,
                  color: Color(0xFFFFD479), size: 38),
                Text('${reward.coins} coins',
                  key: const Key('rocket-personal-coins'),
                  style: const TextStyle(color: Color(0xFF8DF1CE),
                    fontSize: 24, fontWeight: FontWeight.w900)),
                Text(reward.credited ? 'Received in your wallet' : 'Wallet credit pending',
                  style: const TextStyle(color: Colors.white70)),
              ],
              if (reward.medal != null && reward.medal!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Icon(Icons.workspace_premium,
                  color: Color(0xFFFFD479), size: 34),
                Text('${reward.medal} medal received',
                  style: const TextStyle(color: Colors.white)),
              ],
            ]),
          ),
        ),
      ),
    ),
  );
}
